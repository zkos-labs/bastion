// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { BastionPolicy } from "../src/BastionPolicy.sol";
import { BastionAudit } from "../src/BastionAudit.sol";
import { BastionFirewall } from "../src/BastionFirewall.sol";
import { BastionRegistry } from "../src/BastionRegistry.sol";
import { BastionERC8004Registry } from "../src/BastionERC8004Registry.sol";
import { BastionConfidentialGate } from "../src/BastionConfidentialGate.sol";
import { IBastionPolicy } from "../src/interfaces/IBastionPolicy.sol";
import { IBastionAudit } from "../src/interfaces/IBastionAudit.sol";
import { ConfidentialPolicyVerdict } from "@capv/ConfidentialPolicyVerdict.sol";
import { PolicyDomainRegistry } from "@capv/PolicyDomainRegistry.sol";
import { IConfidentialPolicyVerdict } from "@capv/IConfidentialPolicyVerdict.sol";
import { IPolicyDomainRegistry } from "@capv/IPolicyDomainRegistry.sol";

/// @title DeployBastion
/// @notice Deploy the full Bastion protocol to any EVM chain.
/// Testnet-only until the external audit clears (see docs/EVM_READINESS.md §6).
/// Usage (load env first: `source .env`):
///   export BASTION_POLICY_DOMAIN_ID="0x0000000000000000000000000000000000000000000000000000000000000001"
///   forge script script/DeployBastion.s.sol --rpc-url ethereum_sepolia --broadcast --verify
///   forge script script/DeployBastion.s.sol --rpc-url celo_testnet --broadcast --verify
///   forge script script/DeployBastion.s.sol --rpc-url celo --broadcast --verify
///   forge script script/DeployBastion.s.sol --rpc-url base --broadcast --verify
///   forge script script/DeployBastion.s.sol --rpc-url ethereum --broadcast --verify
///   forge script script/DeployBastion.s.sol --rpc-url zksync_sepolia --broadcast --verify
///   forge script script/DeployBastion.s.sol --rpc-url zksync --broadcast --verify
///   forge script script/DeployBastion.s.sol --rpc-url robinhood_testnet --broadcast --verify
///   forge script script/DeployBastion.s.sol --rpc-url robinhood --broadcast --verify
contract DeployBastion is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 domainId = vm.envOr(
            "BASTION_POLICY_DOMAIN_ID",
            bytes32(uint(1)) // testnet default
        );

        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Policy Domain ID:");
        console.logBytes32(domainId);

        vm.startBroadcast(deployerPrivateKey);

        // 0. Deploy CAPV Policy Domain Registry
        PolicyDomainRegistry domainRegistry = new PolicyDomainRegistry();
        console.log("PolicyDomainRegistry deployed at:", address(domainRegistry));

        // 0b. Deploy CAPV Confidential Policy Verdict Guard
        ConfidentialPolicyVerdict capv = new ConfidentialPolicyVerdict(
            IPolicyDomainRegistry(address(domainRegistry))
        );
        console.log("ConfidentialPolicyVerdict deployed at:", address(capv));

        // 1. Deploy Audit (owner wires the firewall after it is deployed)
        BastionAudit audit = new BastionAudit(deployer);
        console.log("BastionAudit deployed at:", address(audit));

        // 2. Deploy Policy
        BastionPolicy policy = new BastionPolicy(deployer);
        console.log("BastionPolicy deployed at:", address(policy));

        // 3. Deploy Registry (original BastionRegistry)
        BastionRegistry registry = new BastionRegistry(deployer);
        console.log("BastionRegistry deployed at:", address(registry));

        // 3b. Deploy ERC-8004 Identity Registry
        BastionERC8004Registry erc8004Registry = new BastionERC8004Registry(deployer);
        console.log("BastionERC8004Registry deployed at:", address(erc8004Registry));

        // 4. Deploy Firewall
        BastionFirewall firewall = new BastionFirewall(
            IBastionPolicy(address(policy)), IBastionAudit(address(audit)), deployer
        );
        console.log("BastionFirewall deployed at:", address(firewall));

        // 5. Authorize the firewall as the sole audit-log writer.
        audit.setFirewall(address(firewall));
        console.log("Audit firewall wired to:", address(firewall));

        // 6. Deploy Confidential Gate (ZK policy verdict + Bastion public policy)
        BastionConfidentialGate confidentialGate = new BastionConfidentialGate(
            IConfidentialPolicyVerdict(address(capv)),
            IBastionPolicy(address(policy)),
            domainId
        );
        console.log("BastionConfidentialGate deployed at:", address(confidentialGate));

        vm.stopBroadcast();

        console.log("\n=== Bastion Protocol Deployed ===");
        console.log("Chain ID:", block.chainid);
        console.log("PolicyDomainRegistry:", address(domainRegistry));
        console.log("ConfidentialPolicyVerdict:", address(capv));
        console.log("Audit:", address(audit));
        console.log("Policy:", address(policy));
        console.log("Registry:", address(registry));
        console.log("ERC-8004 Registry:", address(erc8004Registry));
        console.log("Firewall:", address(firewall));
        console.log("ConfidentialGate:", address(confidentialGate));
    }
}