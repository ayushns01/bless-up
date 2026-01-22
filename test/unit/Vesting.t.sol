// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/ACTXToken.sol";
import "../../src/Vesting.sol";
import "../../src/libraries/Errors.sol";

contract VestingTest is Test {
    ACTXToken public token;
    Vesting public vesting;

    address public treasury = makeAddr("treasury");
    address public reservoir = makeAddr("reservoir");
    address public beneficiary1 = makeAddr("beneficiary1");
    address public beneficiary2 = makeAddr("beneficiary2");

    uint256 public constant TOTAL_SUPPLY = 100_000_000 ether;
    uint256 public constant VESTING_AMOUNT = 1_000_000 ether;

    function setUp() public {
        ACTXToken implementation = new ACTXToken();
        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            treasury,
            reservoir,
            200
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        token = ACTXToken(address(proxy));

        vesting = new Vesting(address(token), treasury);

        vm.startPrank(treasury);
        token.approve(address(vesting), type(uint256).max);
        vm.stopPrank();
    }

    function test_CreateVesting_Success() public {
        vm.prank(treasury);
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);

        (
            uint256 total,
            uint256 start,
            uint256 released,
            ,
            ,
            bool revoked
        ) = vesting.getSchedule(beneficiary1);

        assertEq(total, VESTING_AMOUNT);
        assertEq(start, block.timestamp);
        assertEq(released, 0);
        assertFalse(revoked);
    }

    function test_CreateVesting_RevertIf_ZeroBeneficiary() public {
        vm.prank(treasury);
        vm.expectRevert(Errors.ZeroAddressNotAllowed.selector);
        vesting.createVesting(address(0), VESTING_AMOUNT);
    }

    function test_CreateVesting_RevertIf_ZeroAmount() public {
        vm.prank(treasury);
        vm.expectRevert(Errors.ZeroAmountNotAllowed.selector);
        vesting.createVesting(beneficiary1, 0);
    }

    function test_CreateVesting_RevertIf_AlreadyExists() public {
        vm.startPrank(treasury);
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.BeneficiaryAlreadyExists.selector,
                beneficiary1
            )
        );
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);
        vm.stopPrank();
    }

    function test_Release_RevertBeforeCliff() public {
        vm.prank(treasury);
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);

        vm.warp(block.timestamp + 364 days);

        vm.prank(beneficiary1);
        vm.expectRevert(Errors.NoTokensToRelease.selector);
        vesting.release();
    }

    function test_Release_AfterCliff() public {
        vm.prank(treasury);
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);

        vm.warp(block.timestamp + 365 days);

        vm.prank(beneficiary1);
        vesting.release();

        // After 1 year cliff, roughly 25% should be vested
        uint256 balance = token.balanceOf(beneficiary1);
        assertGt(balance, VESTING_AMOUNT / 5); // > 20%
        assertLe(balance, VESTING_AMOUNT / 4); // <= 25%
    }

    function test_Release_FullVesting() public {
        vm.prank(treasury);
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);

        // Warp past 4 years to ensure full vesting
        vm.warp(block.timestamp + 4 * 365 days + 1 days);

        vm.prank(beneficiary1);
        vesting.release();

        // 2% tax on transfer from vesting contract to beneficiary
        uint256 expectedAfterTax = (VESTING_AMOUNT * 98) / 100;
        assertEq(token.balanceOf(beneficiary1), expectedAfterTax);
    }

    function test_Release_MultipleReleases() public {
        vm.prank(treasury);
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);

        vm.warp(block.timestamp + 2 * 365 days);
        vm.prank(beneficiary1);
        vesting.release();

        uint256 firstRelease = token.balanceOf(beneficiary1);

        vm.warp(block.timestamp + 1 * 365 days);
        vm.prank(beneficiary1);
        vesting.release();

        uint256 totalReceived = token.balanceOf(beneficiary1);
        assertGt(totalReceived, firstRelease);
    }

    function test_Revoke_ReturnsUnvested() public {
        vm.prank(treasury);
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);

        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(treasury);
        vesting.revoke(beneficiary1);

        uint256 treasuryAfter = token.balanceOf(treasury);
        uint256 returned = treasuryAfter - treasuryBefore;

        // After 2 years, roughly 50% vested, so 50% returned
        assertGt(returned, VESTING_AMOUNT / 3); // > 33%
        assertLe(returned, VESTING_AMOUNT / 2); // <= 50%
    }

    function test_VestedAmount_LinearVesting() public {
        vm.prank(treasury);
        vesting.createVesting(beneficiary1, VESTING_AMOUNT);

        assertEq(vesting.vestedAmount(beneficiary1), 0);

        vm.warp(block.timestamp + 365 days);
        uint256 vestedAt1Year = vesting.vestedAmount(beneficiary1);
        assertEq(vestedAt1Year, VESTING_AMOUNT / 4);

        vm.warp(block.timestamp + 365 days);
        uint256 vestedAt2Years = vesting.vestedAmount(beneficiary1);
        assertEq(vestedAt2Years, VESTING_AMOUNT / 2);

        vm.warp(block.timestamp + 2 * 365 days);
        uint256 vestedAt4Years = vesting.vestedAmount(beneficiary1);
        assertEq(vestedAt4Years, VESTING_AMOUNT);
    }
}
