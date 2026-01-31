// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {AgentBattles} from "../src/AgentBattles.sol";

contract DeployScript is Script {
    // Fee recipients
    address constant FEE_SPLITTER = address(0); // TODO: Set FeeSplitter address
    address constant IDEA_CREATOR = 0x35560c57711798c8b13021e8466265f9638140b9; // @promptrbot
    
    function run() public {
        require(FEE_SPLITTER != address(0), "Set FEE_SPLITTER address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        AgentBattles battles = new AgentBattles(FEE_SPLITTER, IDEA_CREATOR);
        
        console2.log("AgentBattles deployed at:", address(battles));
        console2.log("FeeSplitter:", FEE_SPLITTER);
        console2.log("IdeaCreator:", IDEA_CREATOR);
        
        vm.stopBroadcast();
    }
}
