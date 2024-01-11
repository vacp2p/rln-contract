// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { Verifier } from "../src/RlnVerifier.sol";
import { Rln } from "../src/Rln.sol";
import { BaseScript } from "./Base.s.sol";
import { DeploymentConfig } from "./DeploymentConfig.s.sol";

contract Deploy is BaseScript {
    function run() public returns (Rln rln, DeploymentConfig deploymentConfig) {
        deploymentConfig = new DeploymentConfig(broadcaster);

        vm.startBroadcast(broadcaster);
        // step 1: deploy the verifier
        Verifier verifier = new Verifier();
        // step 2: deploy the rln contract
        rln = new Rln(0, 20, address(verifier));
        vm.stopBroadcast();
    }
}
