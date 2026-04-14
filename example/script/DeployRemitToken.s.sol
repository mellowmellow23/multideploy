// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RemitX} from "../src/RemitToken.sol"; 

contract DeployRemitToken is Script {
    function run() external returns (RemitToken {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Adjust constructor arguments if your token requires them
        RemitToken rmxToken = new RemitToken(); 
        
        vm.stopBroadcast();
        
        console.log("RemitToken deployed at:", address(rmxToken));
        return rmxToken;
    }
}