// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Vesting.sol";
import "../src/Airdrop.sol";

contract DeployBonus is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address token = vm.envAddress("ACTX_TOKEN_ADDRESS");
        address owner = vm.envAddress("TREASURY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        Vesting vesting = new Vesting(token, owner);
        console.log("Vesting deployed at:", address(vesting));

        bytes32 merkleRoot = bytes32(0);
        uint256 expiryTime = block.timestamp + 90 days;

        Airdrop airdrop = new Airdrop(token, merkleRoot, expiryTime, owner);
        console.log("Airdrop deployed at:", address(airdrop));

        vm.stopBroadcast();
    }
}
