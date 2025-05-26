# 🏦 SimpleBank Smart Contract

A basic decentralized lending and borrowing contract that allows users to deposit ETH or an ERC20 token (e.g., GigaWei), earn rewards, and borrow against their collateral. Designed as a simple prototype for understanding over-collateralized lending logic.

---

## 📌 What is it for?

`SimpleBank` enables users to:

- Deposit ETH or an ERC20 token as collateral.
- Borrow against their deposited assets using an over-collateralization model.
- Repay debt and optionally receive a share of fees collected from borrowers.
- Withdraw available balances based on their net equity.

This is a basic DeFi lending primitive and can be used in educational demos or simple prototypes for understanding how lending/borrowing protocols like Aave or Compound work at a conceptual level.

---

## ⚙️ How does it work?

### 💰 Deposit

- Users can deposit either native ETH (`depositEther()`) or an ERC20 token (`depositGwei(amount)`).
- Minimum ETH deposit is `0.001 ether`.
- First-time users are tracked via an internal `users` list.

### 💸 Withdraw

- Users may withdraw either token as long as their net balance (collateral - debt) permits.
- Net balance is calculated across both ETH and ERC20 deposits/debts.
- Withdrawals are denied if they would put the user into under-collateralization.

### 🏦 Borrow

- Users can borrow ETH or ERC20 tokens, up to a limit determined by their net collateral value and the `collateralRatio` (default: 120%).
- Borrowing incurs a fee (`borrowFee`, default: 1%) added to the user's debt.

### 🔁 Repay

- ETH debts can be repaid with `repayEth()` (send ETH).
- ERC20 debts can be repaid with `repayGwei(amount)`.
- A portion of the repayment fee is redistributed as rewards to depositors — but this mechanism currently involves looping over all users and may lead to gas inefficiencies.

---

## ✨ Key Features

- 🏦 **Multi-Asset Collateral**: Supports both native ETH and a configurable ERC20 token.
- 🔐 **Over-Collateralized Borrowing**: Borrowing is restricted by a `collateralRatio` (default: 120%).
- 💸 **Borrow Fees**: Fees are charged on borrowing and partially distributed to other users.
- 📤 **Withdrawable Net Balance**: Users can withdraw their tokens as long as they maintain sufficient net collateral.
- ⚙️ **Admin Controls**:
  - `modifyCollateralRatio(uint16)` – Update the collateralization ratio.
  - `modifyBorrowFee(uint16)` – Adjust the borrowing fee.

---

## 📈 View Functions

- `getTotalEthDeposits()` – Total ETH deposited by all users.
- `getTotalGweiDeposits()` – Total ERC20 deposited by all users.
- `getNetBalanceOf(address)` – Net balance after subtracting debt from collateral.
- `getAvailableToBorrowOf(address)` – Max borrowable amount based on current net equity.

---

## ⚠️ Limitations & Warnings

- ⚠️ **Unbounded Loops**: The contract loops over all users in `repayEth()` and `repayGwei()`, which will become **unusable** as the number of users grows. This design is not gas scalable and may block transactions.
- ⚠️ **Missing Claim Logic**: Fee rewards are applied directly to balances without claiming logic, which is not optimal.
- ⚠️ **No Liquidation Mechanism**: There’s no system to handle undercollateralized accounts or force liquidations.
- ⚠️ **Not Production-Ready**: This is a minimal prototype and lacks important DeFi features like interest rates, liquidation, safety checks, oracles, or governance integration.

---

## 🧪 Recommended Use

Use this smart contract for:

- Educational purposes.
- Local testing and learning how lending works.
- Prototyping collateral/debt tracking systems.

---

## 🔧 Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts): ERC20 base logic.

---

## 📜 License

MIT © 2025 — Free to use, modify, and learn from. Not recommended for production deployment without significant upgrades.
