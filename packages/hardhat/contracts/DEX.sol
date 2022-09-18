// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DEX Template
 * @author Gustavo Gonzalrz
 * @dev Automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    IERC20 private token; //instantiates the imported contract
    uint256 public totalLiquidity = 0;
    mapping(address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(address sender, string trade, uint256 amountIn, uint256 amountOut);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(address sender, string trade, uint256 amountOut, uint256 amountIn);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(address sender, uint256 liquidityMinted, uint256 ethIn, uint256 tokensIn);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved();

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX: init - already has liquidity");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        bool success = token.transferFrom(msg.sender, address(this), tokens);
        require(success, "The transfer of tokens failed");

        return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price( //https://www.youtube.com/watch?v=IL7cRj5vzEU
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 xInputWithFee = xInput * 997;
        uint256 numerator = xInputWithFee * yReserves;
        uint256 denominator = xReserves * 1000 + xInputWithFee;
        return (numerator / denominator);
    }

    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     *
     */
    function getLiquidity(address lp) public view returns (uint256) {}

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256) {
        require(msg.value > 0, "cannot swap 0 ETH");

        uint256 ethReserve = address(this).balance - msg.value; //the balance is updated before executing our code, hence we need tu substract msg.value(https://ethereum.stackexchange.com/questions/29991/when-is-this-balance-updated)
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokenOutput = price(msg.value, ethReserve, tokenReserve);
        bool success = token.transfer(msg.sender, tokenOutput);
        require(success, "eth to token exchange failed");

        emit EthToTokenSwap(msg.sender, "Eth to Balloons", msg.value, tokenOutput);
        return tokenOutput;
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput)
        public
        returns (uint256)
    {
        require(tokenInput > 0, "cannot swap 0 tokens. Please send some");

        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethOutput = price(tokenInput, tokenReserve, ethReserve);
        // transfer the tokens to the contract
        bool success = token.transferFrom(msg.sender, address(this), tokenInput);
        require(success, "swap failed while sending your tokens");

        // transfer eth to the user
        (bool sent, ) = msg.sender.call{ value: ethOutput }("");
        require(sent, "transfer of eth failed");

        emit TokenToEthSwap(msg.sender, "Balloons to Eth", ethOutput, tokenInput);
        return ethOutput;
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     * NOTE: When depositing the smart contract should maintain the same ratio. The ratio is only changing while trading, not while providing liquidity
     */
    function deposit() public payable returns (uint256) {
        require(msg.value > 0, "cannot provide liquidity with 0 Eth");
        uint256 ethReserve = address(this).balance - msg.value; //same as ethToToken function the Smart contract balance is updated before running our code
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokensToDeposit = (tokenReserve / ethReserve) * msg.value;

        uint256 liquidityMinted = (msg.value * totalLiquidity) / ethReserve;
        liquidity[msg.sender] = liquidity[msg.sender] + liquidityMinted;
        totalLiquidity = totalLiquidity + liquidityMinted;

        bool success = token.transferFrom(msg.sender, address(this), tokensToDeposit);
        require(success, "Token transfer failed");
        emit LiquidityProvided(msg.sender, 0, msg.value, tokensToDeposit);
        return tokensToDeposit;
    }

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount)
        public
        returns (uint256 eth_amount, uint256 token_amount)
    {}
}
