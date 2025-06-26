// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleBank {
    ERC20 public gigaWei;
    uint public depositMin = 0.001 ether;
    uint public collateralRatio = 12000;
    uint public borrowFee = 100;
    uint public accEthRewardPerToken;
    uint public accGweiRewardPerToken;
    address public admin;
    address[] public users;

    constructor(address _token, address _admin) {
        gigaWei = ERC20(_token);
        admin = _admin;
    }

    event Deposited(address user, uint amount, address token);
    event Withdrawn(address user, uint amount, address token);
    event Borrowed(address user, uint amount, address token);
    event Repaid(address user, uint amount, address token);

    mapping(address => bool) public isUser;

    mapping(address => uint) public userEthBalances;
    mapping(address => uint) public userEthDebts;
    mapping(address => uint) public userEthRewardsDebt;
    mapping(address => uint) public userPendingEthRewards;

    mapping(address => uint) public userGweiBalances;
    mapping(address => uint) public userGweiDebts;
    mapping(address => uint) public userGweiRewardsDebt;
    mapping(address => uint) public userPendingGweiRewards;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin action.");
        _;
    }

    /**
     * Returns the total ETH deposited by users through the 'depositEther()' function
     */
    function getTotalEthDeposits() public view returns (uint) {
        uint totalDeposits = 0;
        for (uint i = 0; i < users.length; i++) {
            totalDeposits += userEthBalances[users[i]];
        }
        return totalDeposits;
    }

    /**
     * Returns the total Gwei deposited by users through the 'depositGwei()' function
     */
    function getTotalGweiDeposits() public view returns (uint) {
        uint totalDeposits = 0;
        for (uint i = 0; i < users.length; i++) {
            totalDeposits += userGweiBalances[users[i]];
        }
        return totalDeposits;
    }

    /**
     * Returns lent - borrowed user balance
     * @param _user user address
     */
    function getNetBalanceOf(address _user) public view returns (uint) {
        uint userBalance = userEthBalances[_user] +
            userGweiBalances[_user] *
            1_000_000_000 wei;
        uint userDebt = userEthDebts[_user] +
            userGweiDebts[_user] *
            1_000_000_000 wei;

        if (userDebt >= userBalance) {
            return 0;
        } else {
            return userBalance - userDebt;
        }
    }

    /**
     * Returns the available amount in ETH value to borrow for a user
     * @param _user user address
     */
    function getAvailableToBorrowOf(address _user) public view returns (uint) {
        uint availableToBorrow = (getNetBalanceOf(_user) * 10000) /
            collateralRatio;
        return (availableToBorrow);
    }

    /**
     * Returns user claimable ETH rewards
     * @param user user address
     */
    function getClaimableEthRewards(address user) external view returns (uint) {
        uint userBalance = userEthBalances[user];
        uint accumulated = (userBalance * accEthRewardPerToken) / 1e18;
        uint owed = accumulated - userEthRewardsDebt[user];
        return userPendingEthRewards[user] + owed;
    }

    /**
     * Updates user claimable ETH rewards
     * @param user user address
     */
    function updateUserEthReward(address user) internal {
        uint userBalance = userEthBalances[user];
        uint accumulated = (userBalance * accEthRewardPerToken) / 1e18;
        uint owed = accumulated - userEthRewardsDebt[user];

        if (owed > 0) {
            userPendingEthRewards[user] += owed;
        }

        userEthRewardsDebt[user] = accumulated;
    }

    /**
     * Updates user claimable Gwei rewards
     * @param user user address
     */
    function updateUserGweiReward(address user) internal {
        uint userBalance = userGweiBalances[user];
        uint accumulated = (userBalance * accGweiRewardPerToken) / 1e18;
        uint owed = accumulated - userGweiRewardsDebt[user];

        if (owed > 0) {
            userPendingGweiRewards[user] += owed;
        }

        userGweiRewardsDebt[user] = accumulated;
    }

    /**
     * Deposits ether into the user bank account
     */

    function depositEther() external payable {
        require(msg.value > 0, "Input must be positive.");
        if (!isUser[msg.sender]) {
            isUser[msg.sender] = true;
            users.push(msg.sender);
        }

        updateUserEthReward(msg.sender);
        userEthBalances[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value, address(0));
    }

    /**
     * Deposits Gwei into the user bank account
     * @param _amount amount of Gwei tokens to deposit
     */

    function depositGwei(uint _amount) external {
        require(_amount > 0, "Input must be positive.");
        gigaWei.transferFrom(msg.sender, address(this), _amount);

        if (!isUser[msg.sender]) {
            isUser[msg.sender] = true;
            users.push(msg.sender);
        }

        updateUserGweiReward(msg.sender);
        userGweiBalances[msg.sender] += _amount;

        emit Deposited(msg.sender, _amount, address(gigaWei));
    }

    /**
     *  Withdraws available ether from user bank account and sends it to user address
     * @param _amount amount of ether to withdraw
     */
    function withdrawEther(uint _amount) external {
        uint netUserBalance = getNetBalanceOf(msg.sender);
        require(netUserBalance >= _amount, "Not enough user net balance");

        updateUserEthReward(msg.sender);
        userEthBalances[msg.sender] -= _amount;

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Withdraw failed.");
        emit Withdrawn(msg.sender, _amount, address(0));
    }

    /**
     *  Withdraws available Gwei from user bank account and sends it to user address
     * @param _amount amount of ether to withdraw
     */
    function withdrawGwei(uint _amount) external {
        uint netUserBalance = getNetBalanceOf(msg.sender);
        require(netUserBalance >= _amount, "Not enough user net balance");

        updateUserGweiReward(msg.sender);
        userGweiBalances[msg.sender] -= _amount;

        gigaWei.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount, address(gigaWei));
    }

    /**
     *  Borrows ether collateralized with ether and Gwei user balances
     * @param _amount amount of eth to borrow
     */
    function borrowEth(uint _amount) external {
        require(
            _amount <= getAvailableToBorrowOf(msg.sender),
            "Amount exceeds available to borrow."
        );
        uint fee = (_amount * borrowFee) / 10000;
        userEthDebts[msg.sender] += _amount + fee;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Borrow failed.");
        emit Borrowed(msg.sender, _amount, address(0));
    }

    /**
     * Borrows Gwei collateralized with ether and Gwei user balances
     * @param _amount amount of Gwei to borrow
     */
    function borrowGwei(uint _amount) external {
        require(
            _amount <= getAvailableToBorrowOf(msg.sender) / 1_000_000_000 wei,
            "Amount exceeds available to borrow."
        );
        uint fee = (_amount * borrowFee) / 10000;
        userGweiDebts[msg.sender] += _amount + fee;
        gigaWei.transfer(msg.sender, _amount);
        emit Borrowed(msg.sender, _amount, address(gigaWei));
    }

    /**
     * Claims available user ether rewards
     */
    function claimEthRewards() external {
        updateUserEthReward(msg.sender);
        uint reward = userPendingEthRewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        userPendingEthRewards[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Claim failed");
    }

    /**
     * Claims available user Gwei rewards
     */
    function claimGweiRewards() external {
        updateUserEthReward(msg.sender);
        uint reward = userPendingGweiRewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        userPendingGweiRewards[msg.sender] = 0;
        gigaWei.transfer(msg.sender, reward);
    }

    /**
     *
     * Repays an ether loan
     */
    function repayEth() external payable {
        require(msg.value > 0, "Input must be positive.");
        require(userEthDebts[msg.sender] > 0, "No debt to repay.");

        uint amount = msg.value;
        uint amountWithoutFee = (amount * 10000) / (borrowFee + 10000);
        uint feePaid = amount - amountWithoutFee;

        uint usersReward = (feePaid * 8) / 10;
        uint totalEth = getTotalEthDeposits();
        if (totalEth > 0) {
            accEthRewardPerToken += (usersReward * 1e18) / totalEth;
        }

        userEthDebts[msg.sender] -= amount;

        emit Repaid(msg.sender, amount, address(0));
    }

    /**
     *  Repays a Gwei loan
     * @param _amount  amount of Gwei to repay
     */
    function repayGwei(uint _amount) external {
        require(_amount > 0, "Input must be positive");
        require(userGweiDebts[msg.sender] > 0, "No debt to repay");

        uint amountWithoutFee = (_amount * 10000) / (borrowFee + 10000);
        uint feePaid = _amount - amountWithoutFee;

        uint usersReward = (feePaid * 8) / 10;
        uint totalGwei = getTotalGweiDeposits();

        for (uint i = 0; i < users.length; i++) {
            userEthBalances[users[i]] +=
                (userEthBalances[users[i]] / totalGwei) *
                usersReward;
        }

        gigaWei.transferFrom(msg.sender, address(this), _amount);
        userGweiDebts[msg.sender] -= _amount;
        emit Repaid(msg.sender, _amount, address(gigaWei));
    }

    /**
     *  Updates collateral ratio needed for loans
     * @param _ratio new collateral ratio
     */
    function modifyCollateralRatio(uint16 _ratio) external onlyAdmin {
        collateralRatio = _ratio;
    }

    /**
     * Updates borrowing fee
     * @param _fee New borrowing fee
     */
    function modifyBorrowFee(uint16 _fee) external onlyAdmin {
        borrowFee = _fee;
    }
}
