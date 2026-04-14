// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SimpleToken} from "../src/SimpleToken.sol";

contract Deploy is Script {
    function run() public {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast();
        SimpleToken token = new SimpleToken(deployer);
        vm.stopBroadcast();

        console.log("SimpleToken deployed to:", address(token));
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
    }
}
