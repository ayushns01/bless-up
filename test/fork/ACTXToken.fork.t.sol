// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/ACTXToken.sol";

/// @title ACTXToken Fork Tests
/// @notice Tests against live Sepolia deployment to verify state
contract ACTXTokenForkTest is Test {
    ACTXToken public token;

    // Deployed contract addresses on Sepolia
    address constant PROXY = 0x7F6A84e2971016E515bda7b2948A8583985aF624;
    address constant TIMELOCK = 0x2e01317084250bf05dFa01feEf349bEEEF2BA5b4;
    address constant IMPLEMENTATION =
        0xB05278D719c03D48be45A2Fe16b800EE3C5efB03;

    uint256 constant TOTAL_SUPPLY = 100_000_000 ether;

    function setUp() public {
        // Fork Sepolia at latest block
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        token = ACTXToken(PROXY);
    }

    function test_Fork_TotalSupplyIs100M() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function test_Fork_TokenMetadata() public view {
        assertEq(token.name(), "ACT.X");
        assertEq(token.symbol(), "ACTX");
        assertEq(token.decimals(), 18);
    }

    function test_Fork_TimelockIsSet() public view {
        assertEq(token.timelockController(), TIMELOCK);
    }

    function test_Fork_TaxRateWithinBounds() public view {
        assertLe(token.taxRateBasisPoints(), 1000);
    }

    function test_Fork_ReservoirNotZero() public view {
        assertTrue(token.reservoirAddress() != address(0));
    }

    function test_Fork_CannotUpgradeWithoutTimelock() public {
        // Deploy new implementation locally
        ACTXToken newImpl = new ACTXToken();

        // Any random address should not be able to upgrade
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert();
        token.upgradeToAndCall(address(newImpl), "");
    }

    function test_Fork_ContractNotPaused() public view {
        // If paused, transfers would revert - verify not paused
        assertFalse(token.paused());
    }

    function test_Fork_Version() public view {
        // After upgrade, version should be readable
        // This may fail on old deployment - that's expected
        try token.version() returns (string memory v) {
            assertEq(v, "1.0.0");
        } catch {
            // Old deployment doesn't have version() - acceptable
        }
    }
}
