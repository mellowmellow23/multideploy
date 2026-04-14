// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RemitToken} from "../src/RemitToken.sol"; 

contract DeployRemitToken is Script {
    function run() external returns (RemitToken) {
        // 1. Get your private key from the .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 2. Derive your public wallet address from that key
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 3. Deploy the token AND set yourself as the owner!
        RemitToken rmxToken = new RemitToken(deployerAddress); 
        
        vm.stopBroadcast();
        
        console.log("RemitToken deployed at:", address(rmxToken));
        return rmxToken;
    }
}
