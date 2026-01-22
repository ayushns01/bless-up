// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/ACTXToken.sol";

contract UpgradeACTX is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("ACTX_PROXY_ADDRESS");
        address timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new implementation
        ACTXToken newImplementation = new ACTXToken();
        console.log("New implementation:", address(newImplementation));

        // 2. Schedule upgrade via timelock
        TimelockController timelock = TimelockController(
            payable(timelockAddress)
        );

        bytes memory upgradeData = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            address(newImplementation),
            ""
        );

        bytes32 salt = keccak256("ACTX_UPGRADE_V2");

        timelock.schedule(
            proxyAddress,
            0,
            upgradeData,
            bytes32(0),
            salt,
            48 hours
        );

        console.log("Upgrade scheduled. Wait 48 hours, then call execute.");
        console.log("Salt:", vm.toString(salt));

        vm.stopBroadcast();
    }
}

contract ExecuteUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("ACTX_PROXY_ADDRESS");
        address timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        address newImplAddress = vm.envAddress("NEW_IMPLEMENTATION_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        TimelockController timelock = TimelockController(
            payable(timelockAddress)
        );

        bytes memory upgradeData = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            newImplAddress,
            ""
        );

        bytes32 salt = keccak256("ACTX_UPGRADE_V2");

        timelock.execute(proxyAddress, 0, upgradeData, bytes32(0), salt);

        console.log("Upgrade executed!");

        vm.stopBroadcast();
    }
}
