// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/ACTXToken.sol";

contract ACTXTokenFuzzTest is Test {
    ACTXToken public token;

    address public treasury = makeAddr("treasury");
    address public reservoir = makeAddr("reservoir");

    uint16 public constant INITIAL_TAX_RATE = 200;
    uint256 public constant TOTAL_SUPPLY = 100_000_000 ether;

    function setUp() public {
        ACTXToken implementation = new ACTXToken();
        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            treasury,
            reservoir,
            INITIAL_TAX_RATE
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        token = ACTXToken(address(proxy));
    }

    function testFuzz_Transfer_TaxCalculation(uint256 amount) public {
        vm.assume(amount > 0 && amount <= TOTAL_SUPPLY);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        vm.prank(treasury);
        token.transfer(user1, amount);

        uint256 balanceBefore = token.balanceOf(reservoir);

        vm.prank(user1);
        token.transfer(user2, amount);

        uint256 expectedTax = (amount * INITIAL_TAX_RATE) / 10000;
        uint256 expectedNet = amount - expectedTax;

        assertEq(token.balanceOf(user2), expectedNet);
        assertEq(token.balanceOf(reservoir) - balanceBefore, expectedTax);
    }

    function testFuzz_SetTaxRate_WithinBounds(uint16 rate) public {
        vm.assume(rate <= 1000);

        vm.prank(treasury);
        token.setTaxRate(rate);

        assertEq(token.taxRateBasisPoints(), rate);
    }

    function testFuzz_SetTaxRate_ExceedsMax_Reverts(uint16 rate) public {
        vm.assume(rate > 1000);

        vm.prank(treasury);
        vm.expectRevert();
        token.setTaxRate(rate);
    }

    function testFuzz_FundAndDistribute(
        uint256 fundAmount,
        uint256 distributeAmount
    ) public {
        vm.assume(fundAmount > 0 && fundAmount <= TOTAL_SUPPLY);
        vm.assume(distributeAmount > 0 && distributeAmount <= fundAmount);

        address rewardManager = makeAddr("rewardManager");
        address recipient = makeAddr("recipient");

        vm.startPrank(treasury);
        token.grantRole(token.REWARD_MANAGER_ROLE(), rewardManager);
        token.fundRewardPool(fundAmount);
        vm.stopPrank();

        vm.prank(rewardManager);
        token.distributeReward(
            recipient,
            distributeAmount,
            keccak256(abi.encodePacked(fundAmount, distributeAmount))
        );

        assertEq(token.balanceOf(recipient), distributeAmount);
        assertEq(token.rewardPoolBalance(), fundAmount - distributeAmount);
    }

    function testFuzz_Transfer_ZeroTaxRate(uint256 amount) public {
        vm.assume(amount > 0 && amount <= TOTAL_SUPPLY);

        vm.prank(treasury);
        token.setTaxRate(0);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        vm.prank(treasury);
        token.transfer(user1, amount);

        vm.prank(user1);
        token.transfer(user2, amount);

        assertEq(token.balanceOf(user2), amount);
    }
}
