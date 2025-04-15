// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleBank {
    ERC20 public gigaWei;
    uint depositMin = 0.001 ether;
    uint collateralRatio = 12000;
    uint borrowFee = 100;
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
    mapping(address => uint) public userGweiBalances;
    mapping(address => uint) public userGweiDebts;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin action.");
        _;
    }

    function getTotalEthDeposits() public view returns (uint) {
        uint totalDeposits = 0;
        for (uint i = 0; i < users.length; i++) {
            totalDeposits += userEthBalances[users[i]];
        }
        return totalDeposits;
    }

    function getTotalGweiDeposits() public view returns (uint) {
        uint totalDeposits = 0;
        for (uint i = 0; i < users.length; i++) {
            totalDeposits += userGweiBalances[users[i]];
        }
        return totalDeposits;
    }

    function depositEther() external payable {
        require(msg.value > 0, "Input must be positive.");

        if (!isUser[msg.sender]) {
            isUser[msg.sender] = true;
            users.push(msg.sender);
        }

        userEthBalances[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value, address(0));
    }

    function depositGwei(uint _amount) external {
        require(_amount > 0, "Input must be positive.");
        gigaWei.transferFrom(msg.sender, address(this), _amount);

        if (!isUser[msg.sender]) {
            isUser[msg.sender] = true;
            users.push(msg.sender);
        }

        userGweiBalances[msg.sender] += _amount;

        emit Deposited(msg.sender, _amount, address(gigaWei));
    }

    function withdrawEther(uint _amount) external {
        uint netUserBalance = getNetBalanceOf(msg.sender);
        require(netUserBalance >= _amount, "Not enough user net balance");
        userEthBalances[msg.sender] -= _amount;

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Withdraw failed.");
        emit Withdrawn(msg.sender, _amount, address(0));
    }

    function withdrawGwei(uint _amount) external {
        uint netUserBalance = getNetBalanceOf(msg.sender);
        require(netUserBalance >= _amount, "Not enough user net balance");
        userGweiBalances[msg.sender] -= _amount;

        gigaWei.transferFrom(address(this), msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount, address(gigaWei));
    }

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

    function getAvailableToBorrowOf(address _user) public view returns (uint) {
        uint availableToBorrow = (getNetBalanceOf(_user) * 10000) /
            collateralRatio;
        return (availableToBorrow);
    }

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

    function repayEth() external payable {
        require(msg.value > 0, "Input must be positive.");
        require(userEthDebts[msg.sender] > 0, "No debt to repay.");

        uint amount = msg.value;
        uint amountWithoutFee = (amount * 10000) / (borrowFee + 10000);
        uint feePaid = amount - amountWithoutFee;

        uint usersReward = (feePaid * 8) / 10;
        uint totalEth = getTotalEthDeposits();

        for (uint i = 0; i < users.length; i++) {
            userEthBalances[users[i]] +=
                (userEthBalances[users[i]] / totalEth) *
                usersReward;
        }
        userEthDebts[msg.sender] -= amount;
        emit Repaid(msg.sender, amount, address(0));
    }

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

    function modifyCollateralRatio(uint16 _ratio) external onlyAdmin {
        collateralRatio = _ratio;
    }

    function modifyBorrowFee(uint16 _fee) external onlyAdmin {
        borrowFee = _fee;
    }
}
