//SPDX-License-Identifier: GNL
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
// INTERFACES USED //
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// LIBRARIES USED //
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

//================================ VERSION 1 ==========================================//

contract Swapper_V1 is Initializable, OwnableUpgradeable {

    using SafeMathUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

// VARIABLES //

    uint256 public fee;
    address private UniswapV2Router02;
    struct player {
        address payable playerAddress; 
        uint256 DAIamount; //the amount of DAI after conversion.
        uint256 ticketsBuyed; //the amount of tockets the user has purchased. 
        bool playing;            
    }

//MAPPINGS

    mapping(uint256 => player) private _idToPlayer;
    CountersUpgradeable.Counter private playerId; 

//EVENTS

    event newPlayer (
        address playerAddress, 
        uint256 DAIamount,
        uint256 ticketsBuyed,
        bool playing
    );

// FUNCTIONS //

    function initialize() 
        public
        initializer {
            __Ownable_init(); 
            UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;           
        }
    /**
    * @notice a function to set the fee for every swap.
    * @dev only the owner of the contract can change the fee.
    * @param _fee the percentage of the fee. It has to be an integer. No decimals allowed.
    */
    function setFee(uint _fee) 
        public
        onlyOwner {
            require(_fee > 0);
            fee = _fee.div(100);        
    }
    /**
    * @notice a function to swap betwen tokens.
    * @dev this is an auxiliar function.
    * @param tokenIn is the address of the token that the user have.
    * @param tokenOut is the address of the token that the user wants.
    * @param amountIn is the amount of tokens the user has.
    * @param amountOutMin is the amount of tokens the user wants.
    */
    function tokensDeposit(address tokenIn, 
                           address tokenOut, 
                           uint256 amountIn, 
                           uint256 amountOutMin)
        public{

            IERC20Upgradeable(tokenIn).transferFrom(msg.sender, address(this), amountIn);
            IERC20Upgradeable(tokenIn).approve(UniswapV2Router02, amountIn);
            address[] memory path;
            path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
            IUniswapV2Router02(UniswapV2Router02).
                swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amountIn, amountOutMin, path, address(this), block.timestamp + 1);
        }






    function _swapETHForTokens(address _tokenIn, 
                                  address _tokenOut, 
                                  uint256 _amountIn, 
                                  uint256 _amountOutMin, 
                                  address _to)
        public
        payable{

            IERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
            IERC20Upgradeable(_tokenIn).approve(UniswapV2Router02, _amountIn);
            address[] memory _path;
            _path = new address[](2);
            _path[0] = _tokenIn;
            _path[1] = _tokenOut;
            IUniswapV2Router02(UniswapV2Router02).
                swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _amountIn, _amountOutMin, _path, _to, block.timestamp + 1);
        }

}
