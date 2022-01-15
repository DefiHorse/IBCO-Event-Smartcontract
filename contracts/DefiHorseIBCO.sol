//SPDX-License-Identifier: MIT
/*
*/
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev Implement Initial Bonding Curve Offering for DefiHorse Token.
 */
contract DefiHorseIBCO is Ownable {
    using SafeERC20 for IERC20;

    event Claim(address indexed account, uint256 userShare, uint256 DFHAmount);
    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    IERC20 public immutable DEFIHORSE;
    IERC20 internal BUSD;

    constructor(
        IERC20 DFH,
        IERC20 _busd) {
        DEFIHORSE = DFH;
        BUSD = _busd;
    }



    uint256 public constant DECIMALS = 10 ** 18; // DefiHorse Token has the same decimals as BNB (18)
    uint256 public constant START = 1642229590; 
    uint256 public constant END = START + 20 minutes; 
    uint256 public constant TOTAL_DISTRIBUTE_AMOUNT = 20040000 * DECIMALS;
    uint256 constant MINIMAL_PROVIDE_AMOUNT = (2 * DECIMALS)/10;
    uint256 constant MINIMAL_USER_AMOUNT = (2000 * DECIMALS)/10;
    uint256 constant THRESHOLD_USER_AMOUNT = 200000 * DECIMALS;
    uint256 public totalProvided = 0;

    mapping(address => uint256) public provided;
    mapping(address => uint256) private accumulated;

    function deposit(uint256 amount) external{
        require(START <= block.timestamp, "The offering has not started yet");
        require(block.timestamp <= END, "The offering has already ended");
        require(DEFIHORSE.balanceOf(address(this)) == TOTAL_DISTRIBUTE_AMOUNT, "Insufficient DEFIHORSE token in contract");
        require(BUSD.allowance(msg.sender, address(this)) >= amount, 'Caller must approve first');
        
        // grab the tokens from msg.sender.
        BUSD.transferFrom(msg.sender, address(this), amount);
        totalProvided += amount;
        provided[msg.sender] += amount;
        accumulated[msg.sender] = Math.max(accumulated[msg.sender], provided[msg.sender]);
        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev Deposits ETH into contract.
     *
     * Requirements:
     * - The offering must be ongoing.
     */
    // function deposit() external payable {
    //     require(START <= block.timestamp, "The offering has not started yet");
    //     require(block.timestamp <= END, "The offering has already ended");
    //     require(DEFIHORSE.balanceOf(address(this)) == TOTAL_DISTRIBUTE_AMOUNT, "Insufficient DEFIHORSE token in contract");

    //     totalProvided += msg.value;
    //     provided[msg.sender] += msg.value;

    //     accumulated[msg.sender] = Math.max(accumulated[msg.sender], provided[msg.sender]);

    //     emit Deposit(msg.sender, msg.value);
    // }

    /**
     * @dev Returns total ETH deposited in the contract of an address.
     */
    function getUserDeposited(address _user) external view returns (uint256) {
        return provided[_user];
    }

    /**
     * @dev Claims DEFIHORSE token from contract by amount calculated on deposited ETH.
     *
     * Requirement:
     * - The offering must have been already ended.
     * - Address has ether deposited in the contract.
     */
    function claim() external {
        require(block.timestamp > END, "The offering has not ended");
        require(provided[msg.sender] > 0, "Empty balance");

        uint256 userShare = provided[msg.sender];
        uint256 DFHAmount = _getEstReceivedToken(msg.sender);
        provided[msg.sender] = 0;

        DEFIHORSE.safeTransfer(msg.sender, DFHAmount);

        emit Claim(msg.sender, userShare, DFHAmount);
    }

    /**
     * @dev Calculate withdrawCap based on accumulated ether
     */
    function _withdrawCap(uint256 userAccumulated) internal pure returns (uint256 withdrawableAmount) {
        if (userAccumulated <= MINIMAL_USER_AMOUNT) {
            return (userAccumulated * 70) / 100;
        }

        if (userAccumulated <= THRESHOLD_USER_AMOUNT) {
            uint256 accumulatedTotal = userAccumulated / DECIMALS;
            uint256 baseNum = (accumulatedTotal*1709)/(10**9);
            uint256 secondNum = (68*accumulatedTotal)/100;
            uint256 takeBackPercentage = (baseNum + 71360 - secondNum) / 1000;
            return (userAccumulated * takeBackPercentage) / 100;
        }

        if (userAccumulated > THRESHOLD_USER_AMOUNT){
            return (userAccumulated * 3) / 100;
        }
    }

    /**
     * @dev Calculate the amount of Ether that can be withdrawn by user
     */
    function _getWithdrawableAmount(address _user) internal view returns (uint256) {
        uint256 userAccumulated = accumulated[_user];
        return Math.min(_withdrawCap(userAccumulated), provided[_user] - _getLockedAmount(_user));
    }

    function getWithdrawableAmount(address _user) external view returns (uint256) {
        return _getWithdrawableAmount(_user);
    }

    /**
     * @dev Estimate the amount of $DefiHorse that can be claim by user
     */
    function _getEstReceivedToken(address _user) internal view returns (uint256) {
        uint256 userShare = provided[_user];
        return (TOTAL_DISTRIBUTE_AMOUNT * userShare) / Math.max(totalProvided, MINIMAL_PROVIDE_AMOUNT);
    }

    /**
     * @dev Calculate locked amount after deposit
     */
    function getLockAmountAfterDeposit(address _user, uint256 amount) external view returns (uint256) {
        uint256 userAccumulated = Math.max(provided[_user] + amount, accumulated[_user]);
        return userAccumulated - _withdrawCap(userAccumulated);
    }

    /**
     * @dev Get user's accumulated amount after deposit
     */
    function getAccumulatedAfterDeposit(address _user, uint256 amount) external view returns (uint256) {
        return Math.max(provided[_user] + amount, accumulated[_user]);
    }

    /**
     * @dev Withdraws ether early
     *
     * Requirements:
     * - The offering must be ongoing.
     * - Amount to withdraw must be less than withdrawable amount
     */
    function withdraw(uint256 amount) external {
        require(block.timestamp > START && block.timestamp < END, "Only withdrawable during the Offering duration");

        require(amount <= provided[msg.sender], "Insufficient balance");

        require(amount <= _getWithdrawableAmount(msg.sender), "Invalid amount");

        provided[msg.sender] -= amount;

        totalProvided -= amount;
       BUSD.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev Get estimated DEFIHORSE token price
     */
    function getEstTokenPrice() public view returns (uint256) {
        return (Math.max(totalProvided, MINIMAL_PROVIDE_AMOUNT) * DECIMALS) / TOTAL_DISTRIBUTE_AMOUNT;
    }

    /**
     * @dev Get estimated amount of DEFIHORSE token an address will receive
     */
    function getEstReceivedToken(address _user) external view returns (uint256) {
        return _getEstReceivedToken(_user);
    }

    /**
     * @dev Get total locked ether of a user
     */
    function getLockedAmount(address _user) external view returns (uint256) {
        return _getLockedAmount(_user);
    }

    function _getLockedAmount(address _user) internal view returns (uint256) {
        uint256 userAccumulated = accumulated[_user];
        return userAccumulated - _withdrawCap(userAccumulated);
    }

    /**
     * @dev Withdraw total ether to owner's wallet
     *
     * Requirements:
     * - Only the owner can withdraw
     * - The offering must have been already ended.
     * - The contract must have ether left.
     */
    function withdrawSaleFunds() external onlyOwner {
        require(END < block.timestamp, "The offering has not ended");
        require(BUSD.balanceOf(address(this)) > 0, "Balance of the contract is empty");

     
        // BUSD.approve(address(this), BUSD.balanceOf(address(this)));
        // BUSD.transferFrom(address(this),msg.sender, BUSD.balanceOf(address(this)));
        BUSD.safeTransfer(msg.sender, BUSD.balanceOf(address(this)));
    }

    /**
     * @dev Withdraw the remaining DEFIHORSE tokens to owner's wallet
     *
     * Requirements:
     * - Only the owner can withdraw.
     * - The offering must have been already ended.
     * - Total DEFIHORSE provided is smaller than MINIMAL_PROVIDE_AMOUNT
     */
    function withdrawRemainedDEFIHORSE() external onlyOwner {
        require(END < block.timestamp, "The offering has not ended");
        require(totalProvided < MINIMAL_PROVIDE_AMOUNT, "Total provided must be less than minimal provided");

        uint256 remainedDefiHorse = TOTAL_DISTRIBUTE_AMOUNT -
            ((TOTAL_DISTRIBUTE_AMOUNT * totalProvided) / MINIMAL_PROVIDE_AMOUNT) - 1;
        DEFIHORSE.safeTransfer(owner(), remainedDefiHorse);
    }

    /**
     * @dev Withdraw the DEFIHORSE tokens that are unclaimed (YES! They are abandoned!)
     *
     * Requirements:
     * - Only the owner can withdraw.
     * - Withdraw date must be more than 30 days after the offering ended.
     */
    function withdrawUnclaimedDEFIHORSE() external onlyOwner {
        require(END + 30 days < block.timestamp, "Withdrawal is unavailable");
        require(DEFIHORSE.balanceOf(address(this)) != 0, "No token to withdraw");

        DEFIHORSE.safeTransfer(owner(), DEFIHORSE.balanceOf(address(this)));
    }
}