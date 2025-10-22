# AeternaFi Testnet
AeternaFi is a next generation DeFi protocol for asset-centric staking, built with modular smart contracts and realistic testnet simulation. This repo contains the verified Sepolia deployment, staking dApp, and core contracts.

## ✅ CI & Formatting Status
![CI](https://github.com/lreasor/aeternafi-testnet/actions/workflows/test.yml/badge.svg?branch=master)

## 🧩 Contracts
🔐 AetUSD.sol
Stablecoin
Omnichain Fungible Token (OFT) via LayerZero
Controlled minting/burning via AetUSDMinter
Owner can set minter

🏗️ AetUSDMinter.sol
Central minting authority for AetUSD
mintTo() for owner-controlled issuance
redeem() for user burn flow
Placeholder for collateral logic (future extension)

🏦 sAetUSD.sol
ERC-4626 vault for staking AetUSD
Users call deposit() (asset-centric) or mint() (share-centric)
Receives AetUSD and mints sAetUSD shares
Withdrawals can optionally route through AetUSDSilo
Uses ConcreteOFT for omnichain support
Secured with ReentrancyGuard

⏳ AetUSDSilo.sol
Cooldown queue for unstaking
Users enqueue withdrawal requests
After cooldown, users claim AetUSD
Owner can distribute rewards

- `src/utils/ConcreteOFT.sol` — omnichain token utility (LayerZero)
- `verification/FlattenedVault.sol` — used for Sepolia Etherscan verification

## 🧪 Testing
- Centralized test suite in `AetAllTest.sol` covers full lifecycle flows:
  - Staking via `deposit()` and `mint()`
  - Unstaking via `withdraw()` and `redeem()`
  - Cooldown queue logic via `AetUSDSilo`
  - Reward distribution and share price impact
  - Round-trip flows with precise asset recovery
  - Edge cases like dust rounding and multiple depositors
- Uses real AetUSD via `AetUSDMintr` for realistic simulation
- Foundry-based with `forge-std/Test.sol` and `StdCheats.sol`
- Includes mock for local testing:
  - `EndpointMock.sol` — used in local tests for omnichain simulation
- Internal helpers for approvals, reward funding, and cooldown inspection
- Labels actors and contracts for trace clarity

## 🛠 Deployment Script
- Deployment to Sepolia is handled via `script/Deploy.s.sol`
- Uses Foundry’s `forge script` and `--broadcast` for live deployment
- Supports reproducible deployment of `sAetUSD` and mocks like `MockLZEndpoint`
- Can be adapted for mainnet or other testnets by changing RPC and constructor args

## 🌐 Deployment
- Sepolia verified contract: [`0xf323aEa80bF9962e26A3499a4Ffd70205590F54d`](https://sepolia.etherscan.io/address/0xf323aEa80bF9962e26A3499a4Ffd70205590F54d#code)
- Frontend deployed via Squarespace: https://www.aeternafi.com/dapplive

## 🧪 Deployment Simulation
After successful testing with AetUSD in `AetAllTest.sol`, the protocol was deployed to Sepolia using WETH as a stand-in for AetUSD. This enables realistic public testing of staking flows and ERC-4626 UX.
- `sAetUSD.sol` deployed with WETH as the underlying asset
- `MockLZEndpoint.sol` — used in Sepolia deployment to simulate LayerZero endpoint
- Supports asset-centric staking via `deposit()` and `mint()`
- Cooldown and reward logic are not active in this deployment

## 🚀 Usage
Interact with the AeternaFi dApp on Ethereum Sepolia using real WETH and sAetUSD — with a seamless onboarding flow.

### ✅ Live on Sepolia
- Visit [AeternaFi dApp](https://www.aeternafi.com/dapplive)
- **Convert Sepolia ETH to WETH** directly in the dApp (no external swap needed)
- **Connect your wallet** via MetaMask using the “Connect Wallet (LIVE)” button
- **Stake AetUSD** (actually WETH) to receive `sAetUSD` shares in your wallet
- **Unstake AetUSD** (WETH) by redeeming `sAetUSD` — no cooldown enforced in this deployment

### 🧪 Testnet Setup
- Requires Sepolia ETH for gas and WETH for staking
- Use [Sepolia faucet](https://sepoliafaucet.com) to get ETH
- Use the built-in ETH→WETH converter in the dApp for staking readiness