// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/ACTXToken.sol";
import "../../src/libraries/Errors.sol";

contract ACTXTokenTest is Test {
    ACTXToken public implementation;
    ACTXToken public token;
    ERC1967Proxy public proxy;

    address public treasury = makeAddr("treasury");
    address public reservoir = makeAddr("reservoir");
    address public rewardManager = makeAddr("rewardManager");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint16 public constant INITIAL_TAX_RATE = 200; // 2%
    uint256 public constant TOTAL_SUPPLY = 100_000_000 ether;

    function setUp() public {
        implementation = new ACTXToken();

        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            treasury,
            reservoir,
            INITIAL_TAX_RATE
        );

        proxy = new ERC1967Proxy(address(implementation), initData);
        token = ACTXToken(address(proxy));

        vm.startPrank(treasury);
        token.grantRole(token.REWARD_MANAGER_ROLE(), rewardManager);
        vm.stopPrank();
    }

    function test_Initialize_MintsTotalSupplyToTreasury() public view {
        assertEq(token.balanceOf(treasury), TOTAL_SUPPLY);
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function test_Initialize_SetsTaxRate() public view {
        assertEq(token.taxRateBasisPoints(), INITIAL_TAX_RATE);
    }

    function test_Initialize_SetsReservoir() public view {
        assertEq(token.reservoirAddress(), reservoir);
    }

    function test_Initialize_TreasuryHasAllRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), treasury));
        assertTrue(token.hasRole(token.UPGRADER_ROLE(), treasury));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), treasury));
        assertTrue(token.hasRole(token.TAX_ADMIN_ROLE(), treasury));
    }

    function test_Initialize_TreasuryAndReservoirAreTaxExempt() public view {
        assertTrue(token.isTaxExempt(treasury));
        assertTrue(token.isTaxExempt(reservoir));
    }

    function test_Initialize_RevertIf_ZeroTreasury() public {
        ACTXToken newImpl = new ACTXToken();
        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            address(0),
            reservoir,
            INITIAL_TAX_RATE
        );
        vm.expectRevert(Errors.ZeroAddressNotAllowed.selector);
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Initialize_RevertIf_ZeroReservoir() public {
        ACTXToken newImpl = new ACTXToken();
        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            treasury,
            address(0),
            INITIAL_TAX_RATE
        );
        vm.expectRevert(Errors.ZeroAddressNotAllowed.selector);
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Initialize_RevertIf_TaxRateExceedsMax() public {
        ACTXToken newImpl = new ACTXToken();
        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            treasury,
            reservoir,
            1001
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TaxRateExceedsMaximum.selector,
                1001,
                1000
            )
        );
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Transfer_DeductsTaxCorrectly() public {
        uint256 amount = 1000 ether;
        uint256 expectedTax = (amount * INITIAL_TAX_RATE) / 10000;
        uint256 expectedNet = amount - expectedTax;

        vm.prank(treasury);
        token.transfer(user1, amount);

        vm.prank(user1);
        token.transfer(user2, amount);

        assertEq(token.balanceOf(user2), expectedNet);
        assertEq(token.balanceOf(reservoir), expectedTax);
    }

    function test_Transfer_TaxExemptSkipsTax() public {
        uint256 amount = 1000 ether;

        vm.prank(treasury);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(reservoir), 0);
    }

    function test_Transfer_EmitsTaxCollected() public {
        uint256 amount = 1000 ether;
        uint256 expectedTax = (amount * INITIAL_TAX_RATE) / 10000;
        uint256 expectedNet = amount - expectedTax;

        vm.prank(treasury);
        token.transfer(user1, amount);

        vm.expectEmit(true, true, false, true);
        emit IACTXToken.TaxCollected(user1, user2, expectedTax, expectedNet);

        vm.prank(user1);
        token.transfer(user2, amount);
    }

    function test_SetTaxRate_UpdatesRate() public {
        uint16 newRate = 500;

        vm.prank(treasury);
        token.setTaxRate(newRate);

        assertEq(token.taxRateBasisPoints(), newRate);
    }

    function test_SetTaxRate_RevertIf_ExceedsMax() public {
        vm.prank(treasury);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TaxRateExceedsMaximum.selector,
                1001,
                1000
            )
        );
        token.setTaxRate(1001);
    }

    function test_SetTaxRate_RevertIf_Unauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        token.setTaxRate(500);
    }

    function test_SetReservoir_UpdatesAddress() public {
        address newReservoir = makeAddr("newReservoir");

        vm.prank(treasury);
        token.setReservoir(newReservoir);

        assertEq(token.reservoirAddress(), newReservoir);
    }

    function test_SetReservoir_RevertIf_ZeroAddress() public {
        vm.prank(treasury);
        vm.expectRevert(Errors.ZeroAddressNotAllowed.selector);
        token.setReservoir(address(0));
    }

    function test_SetTaxExempt_AddsExemption() public {
        vm.prank(treasury);
        token.setTaxExempt(user1, true);

        assertTrue(token.isTaxExempt(user1));
    }

    function test_SetTaxExempt_RemovesExemption() public {
        vm.prank(treasury);
        token.setTaxExempt(user1, true);

        vm.prank(treasury);
        token.setTaxExempt(user1, false);

        assertFalse(token.isTaxExempt(user1));
    }

    function test_FundRewardPool_AddsToPool() public {
        uint256 amount = 1000 ether;

        vm.prank(treasury);
        token.fundRewardPool(amount);

        assertEq(token.rewardPoolBalance(), amount);
        assertEq(token.balanceOf(treasury), TOTAL_SUPPLY - amount);
    }

    function test_FundRewardPool_RevertIf_ZeroAmount() public {
        vm.prank(treasury);
        vm.expectRevert(Errors.ZeroAmountNotAllowed.selector);
        token.fundRewardPool(0);
    }

    function test_DistributeReward_SendsTokens() public {
        uint256 poolAmount = 10000 ether;
        uint256 rewardAmount = 100 ether;

        vm.prank(treasury);
        token.fundRewardPool(poolAmount);

        vm.prank(rewardManager);
        token.distributeReward(user1, rewardAmount);

        assertEq(token.balanceOf(user1), rewardAmount);
        assertEq(token.rewardPoolBalance(), poolAmount - rewardAmount);
    }

    function test_DistributeReward_RevertIf_InsufficientPool() public {
        vm.prank(treasury);
        token.fundRewardPool(100 ether);

        vm.prank(rewardManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InsufficientRewardPool.selector,
                200 ether,
                100 ether
            )
        );
        token.distributeReward(user1, 200 ether);
    }

    function test_DistributeReward_RevertIf_ZeroRecipient() public {
        vm.prank(treasury);
        token.fundRewardPool(100 ether);

        vm.prank(rewardManager);
        vm.expectRevert(Errors.ZeroAddressNotAllowed.selector);
        token.distributeReward(address(0), 50 ether);
    }

    function test_DistributeReward_RevertIf_ZeroAmount() public {
        vm.prank(treasury);
        token.fundRewardPool(100 ether);

        vm.prank(rewardManager);
        vm.expectRevert(Errors.ZeroAmountNotAllowed.selector);
        token.distributeReward(user1, 0);
    }

    function test_DistributeReward_RevertIf_Unauthorized() public {
        vm.prank(treasury);
        token.fundRewardPool(100 ether);

        vm.prank(user1);
        vm.expectRevert();
        token.distributeReward(user2, 50 ether);
    }

    function test_Pause_BlocksTransfers() public {
        vm.prank(treasury);
        token.transfer(user1, 1000 ether);

        vm.prank(treasury);
        token.pause();

        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 500 ether);
    }

    function test_Unpause_AllowsTransfers() public {
        vm.prank(treasury);
        token.transfer(user1, 1000 ether);

        vm.prank(treasury);
        token.pause();

        vm.prank(treasury);
        token.unpause();

        vm.prank(user1);
        token.transfer(user2, 500 ether);

        assertGt(token.balanceOf(user2), 0);
    }

    function test_Pause_RevertIf_Unauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        token.pause();
    }
}
