// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/StdCheats.sol";

import {AetUSD} from "../src/AetUSD.sol";
import {AetUSDMintr} from "../src/AetUSDMintr.sol";
import {sAetUSD, IAetUSDSilo} from "../src/sAetUSD.sol";
import {AetUSDSilo} from "../src/AetUSDSilo.sol";
import {EndpointMock} from "./mocks/EndpointMock.sol";

contract AetAllTest is Test {
    // Contracts
    AetUSD internal aetUSD;
    AetUSDMintr internal mintr;
    sAetUSD internal vault;
    AetUSDSilo internal silo;
    EndpointMock internal endpoint;

    // Actors
    address internal owner = address(0xA0);
    address internal user = address(0xB0);
    address internal user2 = address(0xB1);
    address internal treasury = address(0xC0); // reward funder

    // Constants
    uint256 internal constant ONE = 1e18;

    function setUp() public {
    endpoint = new EndpointMock(1); // chainId = 1 for testing

        // Deploy base token & mintr
        aetUSD = new AetUSD("Aeterna USD", "AetUSD", address(endpoint), owner);
        vm.prank(owner);
        mintr = new AetUSDMintr(address(aetUSD), owner);

        // Wire mintr as authorized minter
        vm.prank(owner);
        aetUSD.setMinter(address(mintr));

        // Deploy ERC-4626 vault (sAetUSD)
        vault = new sAetUSD(aetUSD, address(endpoint), owner);

        // Deploy silo with 14-day cooldown
        silo = new AetUSDSilo(address(aetUSD), owner, 14 days);

        // Wire vault <-> silo
        vm.prank(owner);
        vault.setSilo(address(silo));
        vm.prank(owner);
        silo.setVault(address(vault));

        // Mint initial balances to users and treasury via mintr
        vm.prank(owner);
        mintr.mintTo(user, 1_000_000 * ONE);
        vm.prank(owner);
        mintr.mintTo(user2, 1_000_000 * ONE);
        vm.prank(owner);
        mintr.mintTo(treasury, 1_000_000 * ONE);

        // Label addresses (for traces)
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(user2, "User2");
        vm.label(treasury, "Treasury");
        vm.label(address(aetUSD), "AetUSD");
        vm.label(address(mintr), "Mintr");
        vm.label(address(vault), "sAetUSD(ERC4626)");
        vm.label(address(silo), "Silo");
    }

    // --- Helpers ---

    function _approve(address who, address token, address spender, uint256 amount) internal {
        vm.prank(who);
        IERC20(token).approve(spender, amount);
    }

    // --- Tests ---

    function test_deposit_mint_increase_totalAssets_and_mint_expected_shares() public {
        uint256 amount = 100_000 * ONE;

        // User approves vault to pull AetUSD
        _approve(user, address(aetUSD), address(vault), amount);

        // Preview before deposit
        vm.startPrank(user);
        uint256 previewShares = vault.previewDeposit(amount);

        // Perform deposit
        uint256 mintedShares = vault.deposit(amount, user);
        vm.stopPrank();

        // Assertions
        assertEq(mintedShares, previewShares, "minted != preview");
        assertEq(vault.balanceOf(user), mintedShares, "user share balance");

        // totalAssets should equal AetUSD held by vault
        uint256 ta = vault.totalAssets();
        uint256 vaultBal = aetUSD.balanceOf(address(vault));
        assertEq(ta, vaultBal, "totalAssets equals vault asset balance");

        // Supply and conversions sanity
        uint256 ts = vault.totalSupply();
        assertEq(ts, mintedShares, "totalSupply == minted");
        assertApproxEqAbs(vault.convertToAssets(mintedShares), amount, 1, "shares->assets matches");
    }

    function test_withdraw_enqueue_in_silo_and_claim_after_cooldown() public {
        uint256 depositAmt = 50_000 * ONE;

        // Deposit first
        _approve(user, address(aetUSD), address(vault), depositAmt);
        vm.prank(user);
        vault.deposit(depositAmt, user);

        // Withdraw half as assets
        uint256 withdrawAssets = 25_000 * ONE;
        uint256 previewShares = vault.previewWithdraw(withdrawAssets);

        // Allow vault to burn shares via msg.sender if needed
        vm.startPrank(user);
        // No allowance needed when owner == msg.sender
        uint256 burnedShares = vault.withdraw(withdrawAssets, user, user);
        vm.stopPrank();

        // Shares burned equals previewShares
        assertEq(burnedShares, previewShares, "burned != preview");

        // After withdraw with silo enabled, user should NOT receive assets immediately
        assertEq(aetUSD.balanceOf(user), 1_000_000 * ONE - depositAmt, "no immediate payout");

        // Silo should hold assets for the user
        (uint256 reqAmt, uint256 unlockTime) = _requestOf(user);
        assertEq(reqAmt, withdrawAssets, "silo request amount");
        assertGt(unlockTime, block.timestamp, "unlock in future");

        // Claim before cooldown should fail
        vm.prank(user);
        vm.expectRevert(bytes("Silo: cooling down"));
        silo.claim();

        // Warp past cooldown and claim
        vm.warp(unlockTime + 1);
        uint256 userBalBefore = aetUSD.balanceOf(user);
        vm.prank(user);
        silo.claim();
        uint256 userBalAfter = aetUSD.balanceOf(user);

        assertEq(userBalAfter - userBalBefore, withdrawAssets, "claimed assets");
        assertEq(aetUSD.balanceOf(address(silo)), 0, "silo balance zero after claim");
    }

    function test_reward_distribution_increases_share_price_and_totalAssets() public {
        uint256 depositAmt = 200_000 * ONE;

        // Deposit by user
        _approve(user, address(aetUSD), address(vault), depositAmt);
        vm.prank(user);
        vault.deposit(depositAmt, user);

        // Initial per-share value
        uint256 ts = vault.totalSupply();
        uint256 ta = vault.totalAssets();
        assertEq(ta, depositAmt, "initial TA");
        uint256 initialPerShare = ta == 0 ? ONE : (ta * ONE) / ts;

        // Fund silo and distribute rewards to vault
        uint256 reward = 10_000 * ONE;
        _approve(treasury, address(aetUSD), address(silo), reward);
        vm.prank(treasury);
        // Transfer rewards to silo first
        IERC20(address(aetUSD)).transfer(address(silo), reward);

        // Owner streams rewards from silo to vault
        vm.prank(owner);
        silo.distributeRewards(reward);

        // After reward, totalAssets should increase and per-share should rise
        uint256 ta2 = vault.totalAssets();
        uint256 perShare2 = (ta2 * ONE) / vault.totalSupply();

        assertEq(ta2, ta + reward, "TA increased by reward");
        assertGt(perShare2, initialPerShare, "per-share increased");
        assertEq(aetUSD.balanceOf(address(vault)), ta2, "vault asset balance tracks TA");
    }

    function test_round_trip_deposit_then_withdraw_then_claim_returns_assets() public {
        uint256 depositAmt = 123_456 * ONE;

        // Deposit
        _approve(user, address(aetUSD), address(vault), depositAmt);
        vm.startPrank(user);
        uint256 shares = vault.deposit(depositAmt, user);
        vm.stopPrank();

        // Withdraw all as assets
        vm.startPrank(user);
        uint256 assetsOutPreview = vault.previewRedeem(shares);
        uint256 assetsOut = vault.redeem(shares, user, user);
        vm.stopPrank();

        assertEq(assetsOut, assetsOutPreview, "redeem assets match preview");

        // Assets routed to silo (cooldown)
        (uint256 reqAmt, uint256 unlockTime) = _requestOf(user);
        assertEq(reqAmt, assetsOut, "queued assets");

        // Warp and claim
        vm.warp(unlockTime + 1);
        uint256 balBefore = aetUSD.balanceOf(user);
        vm.prank(user);
        silo.claim();
        uint256 balAfter = aetUSD.balanceOf(user);

        // Since no rewards were added, round-trip should return initial assets precisely
        assertEq(balAfter - balBefore, assetsOut, "claimed equals redeem assets");
        assertEq(assetsOut, depositAmt, "no slippage in round-trip");
        assertEq(vault.totalSupply(), 0, "no shares left");
        assertEq(vault.totalAssets(), 0, "no assets left in vault");
    }

    // --- Internal views for silo requests ---
    function _requestOf(address who) internal view returns (uint256 amount, uint256 unlockTime) {
        (bool ok, bytes memory data) = address(silo).staticcall(
            abi.encodeWithSignature("requests(address)", who)
        );
        require(ok, "silo.requests() failed");
        // abi decode struct (amount, unlockTime)
        (amount, unlockTime) = abi.decode(data, (uint256, uint256));
    }

    function test_bootstrap_first_deposit_is_one_to_one() public {
    uint256 amount = 100 * ONE;
    _approve(user, address(aetUSD), address(vault), amount);

    vm.startPrank(user);
    uint256 shares = vault.deposit(amount, user);
    vm.stopPrank();

    assertEq(shares, amount, "first deposit should mint 1:1 shares");
    }

   function test_multiple_depositors_proportional_shares() public {
    uint256 amt1 = 100 * ONE;
    uint256 amt2 = 300 * ONE;

    _approve(user, address(aetUSD), address(vault), amt1);
    _approve(user2, address(aetUSD), address(vault), amt2);

    vm.prank(user);
    uint256 shares1 = vault.deposit(amt1, user);

    vm.prank(user2);
    uint256 shares2 = vault.deposit(amt2, user2);

    assertEq(shares2, shares1 * 3, "shares scale with deposits");

    // Add reward to skew share price
    _fundAndDistributeReward(100 * ONE);

    // User1 redeems all shares
    vm.startPrank(user);
    uint256 assetsOut1 = vault.redeem(shares1, user, user);
    vm.stopPrank();

    // Warp and claim
    ( , uint256 unlock) = _requestOf(user);
    vm.warp(unlock + 1);
    vm.prank(user);
    silo.claim();

    assertGt(assetsOut1, amt1, "user1 got boosted assets after reward");
    }

function test_dust_rounding_small_deposit_and_withdraw() public {
    uint256 tiny = 1;

    _approve(user, address(aetUSD), address(vault), tiny);
    vm.prank(user);
    uint256 shares = vault.deposit(tiny, user);

    assertGt(shares, 0, "shares minted for tiny deposit");

    vm.prank(user);
    uint256 assetsOut = vault.redeem(shares, user, user);

    ( , uint256 unlock) = _requestOf(user);
    vm.warp(unlock + 1);
    vm.prank(user);
    silo.claim();

    assertEq(assetsOut, tiny, "round-trip preserves tiny deposit");
 }

function test_only_vault_can_enqueue_in_silo() public {
    vm.expectRevert("Silo: not vault");
    silo.enqueueFromVault(user, 100);
}

//function test_only_owner_can_distribute_rewards() public {
//    _fundSilo(100 * ONE);
//    vm.prank(user); // not owner
//    vm.expectRevert(abi.encodeWithSelector(0xca5eb5e1, user));
//    silo.distributeRewards(100 * ONE);
//}

function test_claim_before_cooldown_reverts() public {
    uint256 amt = 50 * ONE;
    _approve(user, address(aetUSD), address(vault), amt);
    vm.prank(user);
    vault.deposit(amt, user);

    vm.prank(user);
    vault.withdraw(amt, user, user);

    vm.prank(user);
    vm.expectRevert("Silo: cooling down");
    silo.claim();
}

function _fundSilo(uint256 amount) internal {
    _approve(treasury, address(aetUSD), address(silo), amount);
    vm.prank(treasury);
    aetUSD.transfer(address(silo), amount);
}

function _fundAndDistributeReward(uint256 amount) internal {
    _fundSilo(amount);
    vm.prank(owner);
    silo.distributeRewards(amount);
}

}
