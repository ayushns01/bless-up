// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/ACTXToken.sol";

contract DeployWithTimelock is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address reservoir = vm.envAddress("RESERVOIR_ADDRESS");
        uint16 taxRate = uint16(vm.envUint("INITIAL_TAX_RATE"));

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ACTXToken
        ACTXToken implementation = new ACTXToken();
        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            treasury,
            reservoir,
            taxRate
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        ACTXToken token = ACTXToken(address(proxy));
        console.log("Token proxy deployed at:", address(proxy));

        // 2. Deploy TimelockController (48hr delay)
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = treasury;
        executors[0] = treasury;

        TimelockController timelock = new TimelockController(
            48 hours,
            proposers,
            executors,
            address(0) // No admin (immutable)
        );
        console.log("Timelock deployed at:", address(timelock));

        // 3. Set timelock as upgrade controller
        token.setTimelockController(address(timelock));
        console.log("Timelock set as upgrade controller");

        // 4. Revoke UPGRADER_ROLE from treasury (optional)
        // token.revokeRole(token.UPGRADER_ROLE(), treasury);

        vm.stopBroadcast();
    }
}
