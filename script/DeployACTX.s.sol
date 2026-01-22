// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ACTXToken.sol";

contract DeployACTX is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address reservoir = vm.envAddress("RESERVOIR_ADDRESS");
        uint16 taxRate = uint16(vm.envUint("INITIAL_TAX_RATE"));

        vm.startBroadcast(deployerPrivateKey);

        ACTXToken implementation = new ACTXToken();
        console.log("Implementation deployed at:", address(implementation));

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
        console.log("Proxy deployed at:", address(proxy));

        ACTXToken token = ACTXToken(address(proxy));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply());
        console.log("Treasury balance:", token.balanceOf(treasury));
        console.log("Tax rate:", token.taxRateBasisPoints());

        vm.stopBroadcast();
    }
}
