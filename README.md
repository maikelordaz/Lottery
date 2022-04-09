# No loss lottery

This is a solidity project about a lottery with the next characteristics:

* It´s an upgradeable smart contract.
* The owner of the contract start an specific amount of lotteries.
* The owner receive a fee on the prize.
* The owner set the ticket price.
* The player can buy any amount of tickets.
* The player can only pay in DAI, USDC or USDT.
* All the tokens will be converted to DAI.
* When the lottery has two days since started, the owner invest the pot on Compound.
* If a player buys a ticket from two days since started, he is going to be added to the next lottery.
* The investment in Compound will be for five days.
* When retire, the owner select the winner, takes the fee on the price and devolutes the money.

## :rocket: INSTALLATION

1. Clone this repo
2. Install the dependencies with 
    > npm install
3. Run test with any of
    > npx hardhat test
    > npm run test

## :computer: WALKTHROUGH

The project is intended to make swaps with Curve Finance, and is using the Stable Swap pool, but if you 
have problems with this pool you can change any swap you want, by changing the corresponding function, 
here you have an example for Uniswap. You just have to change this function




``` javascript
function _swapTokensForDAI(address _tokenIn, uint256 _amountIn) internal {
        
    IERC20Upgradeable(_tokenIn).approve(StableSwap,  _amountIn);
    for(uint128 q = 1; q <= _tokensAccepted.length; q++) {
        if(_tokenIn == _tokensAccepted[q]) {
            int128 _index = int128(q);
            IStableSwap(StableSwap).exchange(_index, 0, _amountIn, 1);
        }
    }
}
```

For this one




``` javascript
function _swapTokensForDAI(address _tokenIn, uint256 _amountIn)
internal{
            
    IERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
    IERC20Upgradeable(_tokenIn).approve(UniswapV2Router02, _amountIn);
    address[] memory _path;
    _path = new address[](2);
    _path[0] = _tokenIn;
    _path[1] = DAIaddress;
    IUniswapV2Router02(UniswapV2Router02).
        swapExactTokensForTokensSupportingFeeOnTransferTokens(_amountIn, 1, _path, address(this), block.timestamp + 1);
}
```

You can also change pools on Uniswap, for example 3pool. here you have the address for this one

> 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7

You can check the other pools [here](https://curve.readthedocs.io/ref-addresses.html?highlight=3pool#implementation-contracts)
  
## :floppy_disk: TECNOLOGIES

+ For swapping
    - Curve Finance
    - Uniswap
+ For investment
    - Compound
+ For randomnes
    - Chainlink VRF V1

## :scroll: NOTES

As this is an upgradeable contract I made some changes on the VRFConsumerBase from this



```javascript
LinkTokenInterface internal immutable LINK;
  address private immutable vrfCoordinator;


  mapping(bytes32 => uint256)
    private nonces;

constructor(address _vrfCoordinator, address _link) {
    vrfCoordinator = _vrfCoordinator;
    LINK = LinkTokenInterface(_link);
  }
```

To this




```javascript
LinkTokenInterface internal LINK;
  address private vrfCoordinator;
  mapping(bytes32 => uint256)
    private nonces;

function init(address _vrfCoordinator, address _link) public {
    vrfCoordinator = _vrfCoordinator;
    LINK = LinkTokenInterface(_link);
  }
```

Removing the inmutable words and changing the constructor to a function wich I initialized
on my contract with the `initializer` modifier.

## :keyboard: CODE

You can follow the code with the coments, they explain every function on the contract.

It is divided in sections so it can be more readable

1. Contract
    1. Variables
    2. Events
    3. Mappings
    4. Functions
        1. Initialization
        2. Lottery settings
        3. Player functions
        4. Compound investment
        5. Picking the winner


## :abacus: TEST

The tests are divided to check every contract functionality one by one.

## :bookmark_tabs: CONTRIBUTE

If you want to contribute just fork the repo and describe the changes you made.

## :balance_scale: LICENSE

MIT







