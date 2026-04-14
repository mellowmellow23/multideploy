// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RemitX} from "../src/RemitToken.sol"; 

contract DeployRemitX is Script {
    function run() external returns (RemitX) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Adjust constructor arguments if your token requires them
        RemitX rmxToken = new RemitX(); 
        
        vm.stopBroadcast();
        
        console.log("RemitX deployed at:", address(rmxToken));
        return rmxToken;
    }
}