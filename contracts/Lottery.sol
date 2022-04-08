//SPDX-License-Identifier: MIT
/**
* @title Lottery
* @author Maikel Ordaz.
* @notice a no loss lotery
* @dev this contract is upgradeable, and this is the first version.
*/
pragma solidity ^0.8.4;

// CONTRACTS INHERITED //
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
// INTERFACES USED //
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/Compound.sol";
// LIBRARIES USED //
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "hardhat/console.sol";

contract Lottery is Initializable, 
                    OwnableUpgradeable, 
                    ReentrancyGuardUpgradeable, 
                    VRFConsumerBase {

    using SafeMathUpgradeable for uint256;

// VARIABLES //

    uint256 public lotteryFee;
    uint256 public slippage;
    uint256 public ticketPrice;
    uint256 numberOfLotteries;
    address private UniswapV2Router02;
    // tokens accepted
    address [] private _tokensAccepted;
    address private DAIaddress;
    IERC20Upgradeable public DAI;
    address private USDCaddress;
    IERC20Upgradeable USDC;
    address private USDTaddress;
    IERC20Upgradeable USDT;    
    CErc20 public cDAI; // token invested

    bytes32 internal keyHash; // identifies which Chainlink oracle to use
    uint internal randomnessFee; // fee to get random number
    uint public randomResult;

    struct player {
        address playerAddress; 
        uint256 DAIamount; // the amount of DAI after conversion.
        uint256 ticketsBuyed; // the amount of tockets the user has purchased.
        uint256 lotteryNumber; 
        bool playing; // sets true when the player register, set false when the player wins or retire.           
    }    
    struct lottery {
        uint256 pot;
        uint256 ticketNumber;
        uint256 startDate;
        uint256 buyingDeadline;
        uint256 finishDate;
        uint256 prize;
        address buyer;
        address winner;
        bool payed;
    }
// EVENTS //
    event newPlayer (
        address playerAddress, 
        uint256 DAIamount,
        uint256 ticketsBuyed,
        uint256 lotteryNumber,
        bool playing
    );    
// MAPPINGS //
    mapping(address => player) private _idToPlayer;
    uint256 private _players;
    mapping(uint256 => lottery) private _idToLottery;
    uint256 private _lotteryId;
// FUNCTIONS //
//--------------------------------- Initialization ---------------------------------------------//

    function initialize()
    public
    initializer {
        __Ownable_init(); 
        __ReentrancyGuard_init();
        UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; 
        DAIaddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        USDCaddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        USDTaddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7; 
        _tokensAccepted.push(DAIaddress);   
        _tokensAccepted.push(USDCaddress);
        _tokensAccepted.push(USDTaddress);    
        DAI = IERC20Upgradeable(DAIaddress);         
        cDAI = CErc20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
        slippage = 5; 
        _players = 0;
        _lotteryId = 0; 
        VRFConsumerBase.init(0xf0d54349aDdcf704F77AE15b96510dEA15cb7952,
                                   0x514910771AF9Ca656af840dff83E8264EcF986CA);
        keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
        randomnessFee = 2 * 10 ** 18; // 2 Link 
    }
//--------------------------------- Lottery settings -------------------------------------------//
    /**
    * @notice a function to set the fee for every swap.
    * @dev only the owner of the contract can change the fee.
    * @param _fee the percentage of the fee.
    */
    function setFee(uint _fee) 
    public
    onlyOwner {
        require(_fee > 0);
        lotteryFee = _fee.div(100);      
    }
    /**
    * @notice a setter function to set the lottery ticket price.
    * @dev only the owner of the contract can change the fee.
    * @param _ticketPrice the lottery ticket price.
    */
    function setTicketPrice(uint256 _ticketPrice) 
    public
    onlyOwner {
        require(_ticketPrice > 0);
        ticketPrice = _ticketPrice;        
    }
    /**
    * @notice a getter function to get the ticket price.
    * @return uint256 the ticket price
    */
    function getTicketPrice()
    public
    view
    returns(uint256) {
        return ticketPrice;
    }
    /**
    * @notice a function to start the lottery process
    * @dev it makes a loop to create the lotteries and to register their dates on the corresponding
    * mapping.
    * @param _numberOfLotteries the number of lotteries the owner allow.
    */
    function startLottery(uint256 _numberOfLotteries)
    public
    onlyOwner {
        numberOfLotteries = _numberOfLotteries;
        uint256 time = block.timestamp;
        for(uint256 i = 0; i < numberOfLotteries; i++) {
            _lotteryId++;
            uint256 _buyingDeadLine = time.add(2 days);
            uint256 _finish = time.add(7 days);
            _idToLottery[_lotteryId] = 
                lottery (0,
                        0,
                        time,
                        _buyingDeadLine,
                        _finish,
                        0,
                        address(0),
                        address(0),
                        false);
            time = _finish;                                                          
        }
        //console.log("Total lotteries created", _lotteryId);            
    }
    /**
    * @notice a function to swap betwen tokens.
    * @dev this is an auxiliar function.
    * @param _tokenIn is the address of the token that the user have.
    * @param _amountIn is the amount of tokens the user has.
    */
    function _swapTokensForDAI(address _tokenIn, uint256 _amountIn)
    internal{

        IERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20Upgradeable(_tokenIn).approve(UniswapV2Router02, _amountIn);
        address[] memory _path;
        _path = new address[](2);
        _path[0] = _tokenIn;
        _path[1] = DAIaddress;
        IUniswapV2Router02(UniswapV2Router02).
            swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amountIn, 1, _path, address(this), block.timestamp + 1);
    }
    /**
    * @notice A function called if the buyer pays with DAI
    * @dev this is an auxiliar function
    */
    function DAIsell(uint256 _amountIn, uint256 _date, uint256 _tickets)
    internal {
        // A loop to iterate between all lotteries.
        for(uint256 j = 1; j < numberOfLotteries ; j++) {
            uint256 starting =_idToLottery[j].startDate;
            uint256 deadlineToBuy = _idToLottery[j].buyingDeadline;
            // A condition to check if the buying date has already passed.
            if(starting <= _date && _date <= deadlineToBuy) {
                // Add the player to the mapping, and emit the event.
                _idToPlayer[msg.sender] =
                    player (msg.sender, 
                        _amountIn,
                        _tickets,
                        j, 
                        true);
                emit newPlayer (msg.sender, 
                                _amountIn,
                                _tickets,
                                j,
                                true);
                // Add the tokens to the pot.
                _idToLottery[j].pot += _amountIn;
                console.log("Lottery number", j);
                // Asign each lottery ticket to the player
                for(uint256 m = 0; m <= _tickets; m++) {
                    _idToLottery[j].ticketNumber++;
                    _idToLottery[j].buyer = msg.sender;
                }    
            }// If the time already passed, I add the player to the next lottery.
            if(_date >= deadlineToBuy) {              
                _idToPlayer[msg.sender] = 
                    player (msg.sender, 
                            _amountIn,
                            _tickets,
                            j.add(1), 
                            true);
                emit newPlayer (msg.sender, 
                                _amountIn,
                                _tickets,
                                j.add(1),
                                true);
                _idToLottery[j.add(1)].pot += _amountIn;
                console.log("Lottery number", j.add(1));
                for(uint256 m = 0; m <= _tickets; m++) {
                    _idToLottery[j.add(1)].ticketNumber++;
                    _idToLottery[j.add(1)].buyer = msg.sender;
                }                
            }
        }               
    }
    /**
    * @notice A function called if the buyer pays with USDC or USDT
    * @dev this is an auxiliar function
    */
    function tokenSell(uint256 _amountIn, uint256 _date, uint256 _tickets, address _tokenIn)
    internal {
        _swapTokensForDAI(_tokenIn, _amountIn);
        for(uint256 j = 1; j < numberOfLotteries ; j++) {
            uint256 starting =_idToLottery[j].startDate;
            uint256 deadlineToBuy = _idToLottery[j].buyingDeadline;
            if(starting <= _date && _date <= deadlineToBuy) {
                _idToPlayer[msg.sender] =
                    player (msg.sender, 
                        _amountIn,
                        _tickets,
                        j, 
                        true);
                emit newPlayer (msg.sender, 
                                _amountIn,
                                _tickets,
                                j,
                                true);
                _idToLottery[j].pot += _amountIn;
                console.log("Lottery number", j);
                for(uint256 m = 0; m <= _tickets; m++) {
                    _idToLottery[j].ticketNumber++;
                    _idToLottery[j].buyer = msg.sender;
                }    
            } if(_date > deadlineToBuy) {             
                _idToPlayer[msg.sender] = 
                    player (msg.sender, 
                            _amountIn,
                            _tickets,
                            j.add(1), 
                            true);
                emit newPlayer (msg.sender, 
                                _amountIn,
                                _tickets,
                                j.add(1),
                                true);
                _idToLottery[j.add(1)].pot += _amountIn;
                console.log("Lottery number", j.add(1));
                for(uint256 m = 0; m <= _tickets; m++) {
                    _idToLottery[j.add(1)].ticketNumber++;
                    _idToLottery[j.add(1)].buyer = msg.sender;
                }                
            }
        }               
    }
//--------------------------------- Player functions -------------------------------------------//
    /**
    * @notice a function to buy the lottery tickets with DAI.
    * @param amountIn the amount of tokens the player pays.
    * @param amountIn is the amount of DAIs payed.
    * @param tokenIn the token used by the player to buy tickets.  
    */
    function buyTicketWithDai(uint256 amountIn, address tokenIn)
    public
    nonReentrant {
        // Some requirements about tokens, tickets and lotteries.
        require(tokenIn == DAIaddress, "We only accept DAI within this function.");
        require(amountIn >= ticketPrice, "You have to buy at least one ticket.");
        require(numberOfLotteries > 0, "There are no lotteries active right now");
        // Transfer all tokens to contract 
        DAI.allowance(msg.sender, address(this)); 
        DAI.transferFrom(msg.sender, address(this), amountIn);
        // Update the players number
        _players++;
        // Calculates the tickets and the actual date
        uint256 tickets = amountIn.div(ticketPrice);
        uint256 playersBuyDate = block.timestamp;
        // Call the auxiliar function
        DAIsell(amountIn, playersBuyDate, tickets);
        console.log("Total tickets:", tickets);
    }
    /**
    * @notice a function to buy the lottery tickets with USDC and USDT.
    * @dev only USDT and USDC are accepted as payments.
    * @dev this functions are individuals for gas saving purpose.
    * @param amountIn the amount of tokens the player pays.
    * @param tokenIn the token used by the player to buy tickets.  
    */
    function buyTicketWithTokens(uint256 amountIn, address tokenIn)
    public
    nonReentrant {
        require(tokenIn == USDTaddress || 
                tokenIn == USDCaddress, 
                "We only accept USDT or USDC tokens within this function.");
        require(amountIn >= ticketPrice, "You have to buy at least one ticket.");
        require(numberOfLotteries > 0, "There are no lotteries active right now");
        IERC20Upgradeable(tokenIn).allowance(msg.sender, address(this)); 
        IERC20Upgradeable(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        _players++;
        uint256 tickets = amountIn.div(ticketPrice);
        uint256 playersBuyDate = block.timestamp;        
        tokenSell(amountIn, playersBuyDate, tickets, tokenIn); 
        console.log("Total tickets:", tickets); 
    }
    /**
    * @notice a function to retire from the lottery.
    * @dev the player can not retire the investment if is already invested, if thats the case the
    * player has to wait until the contract redeem the invest and pick the winner.
    */
    function retirement()
    public
    nonReentrant {        
        // A require to check if the caller is an actual player.
        require(_idToPlayer[msg.sender].playerAddress == msg.sender &&
                _idToPlayer[msg.sender].playing == true, "You are not playing right now");
        // A check to see if the player can retire at the moment.
        uint256 retirementDate = block.timestamp;
        uint256 playersLottery = _idToPlayer[msg.sender].lotteryNumber;
        uint256 lotteryDate = _idToLottery[playersLottery].buyingDeadline;
        require(retirementDate < lotteryDate, 
                "Your money is already invested, wait until the finish date");
        // Transfer the tokens used by the player. DAI equivalent.
        uint256 devolution = _idToPlayer[msg.sender].DAIamount;
        DAI.transferFrom(address(this), msg.sender, devolution);
        // Retire the player from the lottery.
        uint256 _lottery = _idToPlayer[msg.sender].lotteryNumber;
        _idToLottery[_lottery].ticketNumber -= _idToPlayer[msg.sender].ticketsBuyed;
        _idToPlayer[msg.sender] = player (msg.sender, 0, 0, 0, false);
        
    }
//--------------------------------- Compound Investment ----------------------------------------//
    /**
    * @notice a function to make a compound investment
    */
    function potInvestment() 
    public
    onlyOwner {
        uint256 rightNow = block.timestamp;
        // A loop to enter every lottery
        for(uint256 k = 0; k < numberOfLotteries; k++) {
            uint256 potToInvest = _idToLottery[k].pot;            
            require(_idToLottery[k].buyingDeadline == rightNow, "You can not invest yet");
            DAI.approve(address(cDAI), potToInvest);
            require(cDAI.mint(potToInvest) == 0, "mint failed");           
        }
    }    
    /**
    * @notice a function to retire the compound investment
    */
    function retireInvestment() 
    public
    onlyOwner {
        uint256 rightNow = block.timestamp;
        for(uint256 k = 0; k < numberOfLotteries; k++) {
            require(_idToLottery[k].finishDate == rightNow, "You can not retire the money yet.");
            uint256 totalToRedeem = cDAI.balanceOf(address(this));
            uint256 potInvested = _idToLottery[k].pot;
            uint256 _prize = totalToRedeem.sub(potInvested);
            require(cDAI.redeem(totalToRedeem) == 0, "redeem failed");
            _idToLottery[k].prize = _prize;
            //getRandomNumber();                        
        }
    }
    
//--------------------------------- Picking the winner -----------------------------------------//
    /**
    * @notice Functions to get randomnumbers with Chainlink VRF.
    * @dev First the call to the oracle.
    */
    function getRandomNumber() 
    internal
    returns (bytes32 requestId) {        
        require(LINK.balanceOf(address(this)) >= randomnessFee, "Not enough LINK to pay fee");
        requestId = requestRandomness(keyHash, randomnessFee);
    } 
    /**
    * @dev Second the response from the oracle. Inside this one we have the logic to select and 
    * pay the winner. 
    */
    function fulfillRandomness(bytes32 requestId, uint randomness) 
    internal 
    override {
        randomResult = randomness;
        uint256 ID = uint256(requestId);
        // Some requires to check if the payment can proceed.
        uint256 _profit =  _idToLottery[ID].prize;
        uint256 _ownerFee = _profit.mul(lotteryFee);
        uint256 _prize = _profit.sub(_ownerFee);        
        require(_profit > 0, "There are no prize");
        require(_idToLottery[ID].payed == false);
        // The selection of the winner
        uint256 _winnerID = randomResult % _idToLottery[ID].ticketNumber;
        address _winnerAddress = _idToLottery[_winnerID].buyer;        
        // Transfer the invested amount and the profits to the winner.
        uint256 _money = _prize + _idToPlayer[_winnerAddress].DAIamount;
        //address _winnerAddress = _idToPlayer[_winnerID].playerAddress;
        DAI.transferFrom(address(this), owner(), _ownerFee);
        DAI.transferFrom(address(this), _winnerAddress, _money);
        // Update the lottery and the player. 
        _idToLottery[ID].winner = _winnerAddress;
        _idToLottery[ID].payed = true;
        _idToPlayer[_winnerAddress] = player(_winnerAddress, 0, 0, 0, false);
    }  
}          
         
